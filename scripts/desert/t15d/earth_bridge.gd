extends Node3D
## Tarefa de cenário única: usa a aparência da terra, sem habilidade nem carga.
signal assembled
var hole: Dictionary
var raised := false
var _deck: StaticBody3D
var _shape: CollisionShape3D
var _hinge: Node3D
var _angle := 0.0
func configure(data: Dictionary) -> void:
	hole = data
func _ready() -> void:
	add_to_group("earth_bridges")
	var start := Vector3(float(hole.start)-0.12,float(hole.from_y),0)
	var finish := Vector3(float(hole.end)+0.12,float(hole.to_y),0)
	var span := finish-start
	_angle = atan2(span.y,span.x)
	_hinge = Node3D.new()
	_hinge.position = start
	_hinge.rotation.z = _angle
	add_child(_hinge)
	_deck = StaticBody3D.new()
	_deck.name = "EarthDeck"
	_deck.collision_layer = 1
	_deck.position = Vector3(span.length()*0.5,-0.13,0)
	_hinge.add_child(_deck)
	var size := Vector3(span.length(),0.26,3.8)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.disabled = true
	_deck.add_child(_shape)
	var mesh := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = size
	mesh.mesh = slab
	var earth := StandardMaterial3D.new()
	earth.albedo_texture = preload("res://assets/desert/phase01/sandstone.png")
	earth.albedo_color = Color("#bd8e60")
	mesh.material_override = earth
	_deck.add_child(mesh)
	_deck.hide()
	# Marcas sobre o piso das duas margens. Nunca ficam flutuando sobre o vão.
	for point in [start-Vector3(0.65,0,0),finish+Vector3(0.65,0,0)]:
		var mark := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.24
		ring.outer_radius = 0.36
		ring.rings = 16
		ring.ring_segments = 6
		mark.mesh = ring
		mark.scale.y = 0.13
		mark.position = point+Vector3(0,0.035,-0.85)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#eec27f")
		mark.material_override = material
		add_child(mark)
func raise_bridge(animated := true) -> void:
	if raised: return
	raised = true
	_deck.show()
	if not animated:
		_shape.set_deferred("disabled",false)
		return
	# A peça sobe como parede e gira pela margem até virar passagem.
	_hinge.rotation.z = _angle+PI*0.5
	var tween := create_tween()
	tween.tween_property(_hinge,"rotation:z",_angle,0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_shape.set_deferred("disabled",false)
		assembled.emit())
