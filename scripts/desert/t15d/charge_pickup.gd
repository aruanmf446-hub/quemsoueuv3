extends Area3D
## Reposição real: cheia não é consumida; ID persiste ao descarregar o distrito.
signal collected(id: String, kind: String)
signal full_touched(kind: String)
var pickup_id := ""
var kind := "attack"
var _visual: Node3D
var _time := 0.0
var _player: Node3D
var _taken := false
var _announced_full := false
func _ready() -> void:
	add_to_group("campaign_pickups")
	set_meta("pickup_id",pickup_id)
	set_meta("kind",kind)
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	shape.shape = sphere
	shape.position.y = 0.7
	add_child(shape)
	_visual = Node3D.new()
	_visual.position.y = 0.85
	add_child(_visual)
	var color: Color = {"attack": Color("#e4bd71"), "defense": Color("#79cceb"), "health": Color("#ff5d5d")}.get(kind, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color*0.4
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.30
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.rotation_degrees.x = 90
	ring.material_override = mat
	_visual.add_child(ring)
	var icon := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polygon: PackedVector2Array
	if kind == "attack": polygon = PackedVector2Array([Vector2(-0.06,-0.2),Vector2(-0.06,0.11),Vector2(0,0.24),Vector2(0.06,0.11),Vector2(0.06,-0.2)])
	elif kind == "health":
		polygon = PackedVector2Array()
		for step in range(28):
			var t := TAU*step/28.0
			polygon.append(Vector2(16*pow(sin(t),3),13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t))*0.0125)
	else: polygon = PackedVector2Array([Vector2(-0.16,0.16),Vector2(0.16,0.16),Vector2(0.13,-0.07),Vector2(0,-0.22),Vector2(-0.13,-0.07)])
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index in indices:
		var point := polygon[index]
		st.add_vertex(Vector3(point.x,point.y,0))
	st.generate_normals()
	icon.mesh = st.commit()
	var icon_mat := mat.duplicate() as StandardMaterial3D
	icon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	icon.material_override = icon_mat
	_visual.add_child(icon)
	if kind == "attack":
		var guard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.28,0.04,0.03)
		guard.mesh = mesh
		guard.position.y = -0.10
		guard.material_override = mat
		_visual.add_child(guard)
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"): _try_collect(body))
func _physics_process(delta: float) -> void:
	_time += delta
	_visual.position.y = 0.85+sin(_time*2.8)*0.06
	_visual.rotation.y = sin(_time*1.5)*0.24
	if not is_instance_valid(_player): _player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player) and absf(_player.position.x-global_position.x)<0.65 and absf(_player.position.y-global_position.y)<1.15:
		_try_collect(_player)
	elif is_instance_valid(_player) and absf(_player.position.x-global_position.x)>1.1:
		_announced_full = false
func _try_collect(body: Node3D) -> void:
	if _taken or not body.has_method("restore_charge"): return
	if not body.restore_charge(kind):
		if not _announced_full and not body.is_dead:
			_announced_full = true
			full_touched.emit(kind)
		return
	_taken = true
	collected.emit(pickup_id,kind)
	queue_free()
