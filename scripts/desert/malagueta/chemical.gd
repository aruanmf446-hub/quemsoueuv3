extends Area3D
## Existing materials; telegraphed projectile, no authored character/animation asset.
signal expired
var kind := "red"
var direction := Vector3.LEFT
var speed := 5.0
var damage := 1
var amplitude := 0.45
var elapsed := 0.0
var lifetime := 6.0
var warning := 0.65
var start := Vector3.ZERO
var active := true
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	start = position
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.23
	mesh.height = 0.46
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = preload("res://scripts/desert/t15d/terrain.gd").stone_material(Color("#79dc68") if kind == "green" else Color("#e96753"))
	add_child(visual)
	body_entered.connect(_hit)
func _physics_process(delta: float) -> void:
	if not active: return
	elapsed += delta
	if elapsed < warning: return
	var time := elapsed-warning
	position = start + direction*speed*time
	if kind == "green": position.y += sin(time*5.0)*amplitude
	if time > lifetime:
		remove()
		return
	for body in get_overlapping_bodies(): _hit(body)
func _hit(body: Node3D) -> void:
	if not active or elapsed < warning or not body.is_in_group("player"): return
	body.take_damage(damage,global_position.x)
	remove()
func remove() -> void:
	if not active: return
	active = false
	expired.emit()
	queue_free()
