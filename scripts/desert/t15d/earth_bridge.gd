extends Node3D
## Mecanismos pontuais do cenário: passagem giratória, portão e plataforma de carga.
## Mesma interação contextual, sem adicionar habilidade nem consumir cargas.
signal assembled
var hole: Dictionary
var raised := false
var _deck: StaticBody3D
var _shape: CollisionShape3D
var _hinge: Node3D
var _angle := 0.0
var _kind := "bridge"
func configure(data: Dictionary) -> void:
	hole = data
	_kind = str(data.get("task_kind","bridge"))
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
	if _kind=="gate":
		_hinge.position=Vector3((start.x+finish.x)*0.5,start.y,0)
		_hinge.rotation=Vector3.ZERO
		_deck.position=Vector3(0,2.6,0)
		box.size=Vector3(2.4,5.2,3.6)
		slab.size=box.size
		earth.albedo_texture=null
		earth.albedo_color=Color("#795739")
		_deck.show()
		_shape.disabled=false
		var detail:=preload("res://scripts/desert/t15d/city_props.gd").new()
		_deck.add_child(detail)
		for y in [-1.8,0.0,1.8]:detail._box(Vector3(0,y,1.84),Vector3(2.4,0.12,0.10),"metal")
		for x in [-1.16,1.16]:detail._box(Vector3(x,0,1.84),Vector3(0.12,5.2,0.10),"metal")
		detail._flush()
	elif _kind=="lift":
		_deck.show()
		_deck.position.y-=1.6
	if int(hole.get("theme",4)) in [2,3,5,7,9,10] and _kind!="gate":
		earth.albedo_texture=null
		earth.albedo_color=Color("#6b1018") if int(hole.theme)==3 else Color("#816044")
	# Estrutura do mecanismo, fora da pista; o piso e a porta têm seus próprios colisores.
	var props := preload("res://scripts/desert/t15d/city_props.gd").new()
	add_child(props)
	if _kind=="gate":
		props.place_asset("capital_archway",Vector3((start.x+finish.x)*0.5,start.y,-3.5),5.0)
	elif _kind=="lift":
		for x in [start.x,finish.x]:
			props._box(Vector3(x,start.y+1.9,-2),Vector3(0.18,3.8,0.18),"wood")
		props._box(Vector3((start.x+finish.x)*0.5,start.y+3.8,-2),Vector3(span.length()+0.4,0.2,0.2),"wood")
	props._flush()
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
		if _kind=="gate": _hinge.position.y+=5.5
		elif _kind=="lift": _deck.position.y=-0.13
		_shape.set_deferred("disabled",false)
		return
	# A peça sobe como parede e gira pela margem até virar passagem.
	var tween := create_tween()
	_shape.set_deferred("disabled",true)
	if _kind=="gate":
		tween.tween_property(_hinge,"position:y",_hinge.position.y+5.5,0.8)
	elif _kind=="lift":
		tween.tween_property(_deck,"position:y",-0.13,0.8)
	else:
		_hinge.rotation.z = _angle+PI*0.5
		tween.tween_property(_hinge,"rotation:z",_angle,0.8)
	tween.tween_callback(func() -> void:
		_shape.set_deferred("disabled",false)
		assembled.emit())
