extends AnimatableBody3D
## Flat excavation file: safe upper face, hazardous teeth below the walkable top.
@export var travel := 0.65
@export var speed := 0.65
@export var span := 3.4
@export var damage := 1
var origin := Vector3.ZERO
var elapsed := 0.0
var enabled := true
var _shaft: MeshInstance3D
var _shaft_mesh: BoxMesh
func _ready() -> void:
	add_to_group("mining_files")
	origin = position
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span,0.3,2.0)
	shape.shape = box
	shape.position.y = -0.15
	add_child(shape)
	var visual := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = box.size
	visual.mesh = blade
	visual.position = shape.position
	visual.material_override = preload("res://scripts/desert/t15d/terrain.gd").stone_material(Color("#77818a"))
	add_child(visual)
	var metal:=StandardMaterial3D.new()
	metal.albedo_color=Color("#a2acba")
	metal.metallic=0.65
	metal.roughness=0.5
	visual.material_override=metal
	_shaft=MeshInstance3D.new()
	_shaft_mesh=BoxMesh.new()
	_shaft.mesh=_shaft_mesh
	_shaft.material_override=metal
	add_child(_shaft)
	for side in [-1,1]:
		var danger := Area3D.new()
		danger.collision_layer = 0
		danger.collision_mask = 2
		var teeth := CollisionShape3D.new()
		var end := BoxShape3D.new()
		end.size = Vector3(0.18,0.24,1.8)
		teeth.shape = end
		teeth.position = Vector3(side*(span*0.5+0.07),-0.37,0)
		danger.add_child(teeth)
		add_child(danger)
		danger.body_entered.connect(func(body: Node3D) -> void:
			if enabled and body.is_in_group("player"): body.take_damage(damage,global_position.x))
func _physics_process(delta: float) -> void:
	if not enabled: return
	elapsed += delta
	position.x = origin.x + sin(elapsed*speed/maxf(travel,0.01))*travel
	var wall:= -12.0 if origin.x<0 else 12.0
	_shaft_mesh.size=Vector3(absf(wall-position.x),0.18,0.35)
	_shaft.position=Vector3((wall-position.x)*0.5,-0.18,-1.25)
